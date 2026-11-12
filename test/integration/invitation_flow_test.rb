require "test_helper"

# The invitee's side: GET /invitations/:token and what follows (B7 to B9, B12).
class InvitationFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @household = households(:smith_home)
    @alice = users(:alice)
    # dana@test.com has an account (and no household); newbie@test.com has none.
    @invitation = Invitation.invite(household: @household, email: "dana@test.com", inviter: @alice)
    @newcomer = Invitation.invite(household: @household, email: "newbie@test.com", inviter: @alice)
  end

  def sign_up_from_invitation(invitation, params = {})
    post user_registration_path, params: { invitation_token: invitation.token, user: {
      first_name: "Newbie", email: invitation.email, password: "password123", password_confirmation: "password123"
    }.merge(params) }
  end

  # ---- Unknown, tampered and closed tokens --------------------------------------

  test "an unknown token is shown clearly, with a 404" do
    get invitation_path("nope")

    assert_response :not_found
    assert_select "h1", "Ce lien ne mène à aucune invitation"
    assert_select "a[href=?]", new_user_registration_path
  end

  test "a tampered token is treated like an unknown one and leaks nothing" do
    get invitation_path(@invitation.token + "x")

    assert_response :not_found
    assert_select "h1", "Ce lien ne mène à aucune invitation"
    assert_no_match @invitation.email, response.body
    assert_no_match @household.name, response.body
  end

  test "an expired invitation says so, with its date" do
    travel 15.days do
      get invitation_path(@invitation.token)

      assert_response :gone
      assert_select "h1", "Cette invitation n'est plus valable"
      assert_match "Elle a expiré le", response.body
      assert_select "form[action=?]", user_registration_path, 0
    end
    assert_predicate @invitation.reload, :expired?
  end

  test "a cancelled invitation says so" do
    @invitation.cancel!
    get invitation_path(@invitation.token)

    assert_response :gone
    assert_select "h1", "Cette invitation n'est plus valable"
    assert_match "a annulé cette invitation", response.body
  end

  test "a declined invitation says so" do
    @invitation.decline!(users(:dana))
    get invitation_path(@invitation.token)

    assert_response :gone
    assert_select "h1", "Vous avez refusé cette invitation"
  end

  test "a used invitation says so, and offers the household to its member" do
    @invitation.claim_for!(users(:dana))
    @invitation.accept!(users(:dana))

    get invitation_path(@invitation.token)
    assert_response :gone
    assert_select "h1", "Cette invitation a déjà été utilisée"

    sign_in users(:dana)
    get invitation_path(@invitation.token)
    assert_select "h1", "Cette invitation a déjà été utilisée"
  end

  # ---- B7: a signed-out visitor ----------------------------------------------------

  test "signed out, the link opens the sign-up with the invited address read-only" do
    get invitation_path(@newcomer.token)

    assert_response :success
    assert_select "h1", "Rejoindre Smith Home"
    assert_select "input[name=invitation_token][value=?]", @newcomer.token
    assert_select "input[type=email][readonly][value=?]", "newbie@test.com"
    assert_select "a[href=?]", new_user_session_path
  end

  test "signed out, an address with an account and one without get the same screen (no enumeration)" do
    existing = @invitation
    normalise = lambda do |invitation, body|
      body.gsub(invitation.token, "TOKEN").gsub(invitation.email, "EMAIL")
          .gsub(/<meta name="csrf-token"[^>]*>/, "").gsub(/<input[^>]*authenticity_token[^>]*>/, "")
    end

    get invitation_path(existing.token)
    with_account = normalise.call(existing, response.body)
    get invitation_path(@newcomer.token)
    without_account = normalise.call(@newcomer, response.body)

    assert_equal with_account, without_account
  end

  test "signing up from the link confirms the account, records the invitee and does not join" do
    assert_no_emails do
      assert_no_difference "HouseholdMember.count" do
        sign_up_from_invitation(@newcomer)
      end
    end

    user = User.find_by!(email: "newbie@test.com")
    assert_predicate user, :confirmed?
    assert_equal user, @newcomer.reload.invitee
    assert_predicate @newcomer, :pending?
    assert_nil user.household
    assert_redirected_to waiting_invitation_path(@newcomer.token)
  end

  test "the address of the invitation wins over a tampered one in the form" do
    assert_difference "User.count", 1 do
      sign_up_from_invitation(@newcomer, email: "someone-else@test.com")
    end

    assert User.exists?(email: "newbie@test.com")
    assert_not User.exists?(email: "someone-else@test.com")
  end

  test "a sign-up error re-renders the invitation screen, not the generic one" do
    sign_up_from_invitation(@newcomer, password: "x", password_confirmation: "x")

    assert_response :unprocessable_entity
    assert_select "h1", "Rejoindre Smith Home"
    assert_select "input[type=email][readonly][value=?]", "newbie@test.com"
  end

  test "an existing account that signs up from the link is sent to sign in, then back to the invitation" do
    invitation = @invitation # dana@test.com already has an account
    get invitation_path(invitation.token)

    assert_no_difference "User.count" do
      sign_up_from_invitation(invitation)
    end
    assert_redirected_to new_user_session_path

    users(:dana).update!(password: "password123")
    post user_session_path, params: { user: { email: "dana@test.com", password: "password123" } }
    assert_redirected_to invitation_path(invitation.token)
  end

  test "an old sign-up link with the token lands on the invitation screen" do
    get new_user_registration_path(invitation_token: @invitation.token)

    assert_redirected_to invitation_path(@invitation.token)
  end

  # ---- B9: signed in, with the right address ----------------------------------------

  test "signed in without a household: the accept screen, then the claim, then the waiting screen" do
    sign_in users(:dana)

    get invitation_path(@invitation.token)
    assert_response :success
    assert_select "h1", /Alice vous invite à rejoindre Smith Home/
    assert_select "form[action=?]", claim_invitation_path(@invitation.token)
    assert_select "form[action=?]", decline_invitation_path(@invitation.token)

    assert_no_difference "HouseholdMember.count" do
      post claim_invitation_path(@invitation.token)
    end
    assert_redirected_to waiting_invitation_path(@invitation.token)
    assert_equal users(:dana), @invitation.reload.invitee

    get invitation_path(@invitation.token)
    assert_redirected_to waiting_invitation_path(@invitation.token)

    follow_redirect!
    assert_response :success
    assert_select "h1", "Alice prépare encore le foyer"
  end

  test "signed in with a household: the screen asks to leave it first and offers no way to continue" do
    invitation = Invitation.invite(household: @household, email: users(:carol).email, inviter: @alice)
    sign_in users(:carol)

    get invitation_path(invitation.token)
    assert_response :success
    assert_select ".alert-box", /quittez d'abord Jones Home/
    assert_select "form[action=?]", claim_invitation_path(invitation.token), 0
    assert_select "form[action=?]", decline_invitation_path(invitation.token)

    post claim_invitation_path(invitation.token)
    assert_nil invitation.reload.invitee
    post accept_invitation_path(invitation.token)
    assert_equal households(:jones_home), users(:carol).reload.household
  end

  test "signed in with another account: a variant that masks the invited address" do
    sign_in users(:carol)

    get invitation_path(@invitation.token)

    assert_response :success
    assert_select "h1", "Cette invitation est pour une autre adresse"
    assert_select ".alert-box", /carol@test\.com/
    assert_no_match "dana@test.com", response.body
    assert_select "form[action=?]", destroy_user_session_path
  end

  test "someone who is already a member sees that the link has been used" do
    invitation = @household.invitations.build(email: users(:bob).email, token: "bob-token",
                                              expires_at: 1.day.from_now, last_sent_at: Time.current)
    invitation.save!(validate: false)
    # a member of the household who still holds an open invitation to it
    sign_in users(:bob)

    get invitation_path(invitation.token)

    assert_select "h1", "Vous faites déjà partie de ce foyer"
  end

  test "declining closes the invitation, leaves the household alone and names no one" do
    sign_in users(:dana)

    assert_no_difference [ "HouseholdMember.count", "Household.count" ] do
      post decline_invitation_path(@invitation.token)
    end

    assert_redirected_to dashboard_path
    assert_equal "Invitation refusée.", flash[:notice]
    assert_predicate @invitation.reload, :declined?
  end

  test "only the addressee can decline" do
    sign_in users(:carol)

    post decline_invitation_path(@invitation.token)

    assert_predicate @invitation.reload, :pending?
  end

  test "claim, accept and decline need a session" do
    post claim_invitation_path(@invitation.token)
    assert_redirected_to invitation_path(@invitation.token)
    post accept_invitation_path(@invitation.token)
    post decline_invitation_path(@invitation.token)

    assert_predicate @invitation.reload, :pending?
    assert_nil @invitation.invitee
  end

  # ---- The last step and the pre-join access ------------------------------------------

  test "accepting joins the household, only after the claim" do
    sign_in users(:dana)

    post accept_invitation_path(@invitation.token)
    assert_nil users(:dana).reload.household

    post claim_invitation_path(@invitation.token)
    post accept_invitation_path(@invitation.token)

    assert_redirected_to household_path(@household)
    assert_equal "Vous avez rejoint le foyer.", flash[:notice]
    assert_equal @household, users(:dana).reload.household
    assert_predicate @invitation.reload, :accepted?
  end

  test "the waiting screen is for the invitee only" do
    get waiting_invitation_path(@invitation.token)
    assert_redirected_to invitation_path(@invitation.token)

    sign_in users(:dana)
    get waiting_invitation_path(@invitation.token) # not claimed yet
    assert_redirected_to invitation_path(@invitation.token)

    @invitation.claim_for!(users(:dana))
    get waiting_invitation_path(@invitation.token)
    assert_response :success
    assert_select "a[href=?]", dashboard_path
    assert_select "form[action=?]", decline_invitation_path(@invitation.token)
  end

  test "an invitee resumes the waiting screen after signing in again" do
    users(:dana).update!(password: "password123")
    @invitation.claim_for!(users(:dana))

    post user_session_path, params: { user: { email: "dana@test.com", password: "password123" } }

    assert_redirected_to waiting_invitation_path(@invitation.token)
  end

  test "the no-household home offers to resume an invitation in progress" do
    sign_in users(:dana)
    get dashboard_path
    assert_select ".callout", 0

    @invitation.claim_for!(users(:dana))
    get dashboard_path

    assert_select ".callout a[href=?]", waiting_invitation_path(@invitation.token)
  end

  test "once cancelled, an invitee's access disappears and the waiting screen closes" do
    sign_in users(:dana)
    @invitation.claim_for!(users(:dana))
    @invitation.cancel!

    get waiting_invitation_path(@invitation.token)

    assert_redirected_to invitation_path(@invitation.token)
  end

  test "the household helper tells who may read the setup before joining" do
    @invitation.claim_for!(users(:dana))

    assert @invitation.grants_setup_access_to?(users(:dana))
    assert_not @invitation.grants_setup_access_to?(users(:carol))
  end
end
