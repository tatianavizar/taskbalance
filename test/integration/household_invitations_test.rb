require "test_helper"

# The household's side: B3 to B5, B13, B15, and the invitation email (B6).
class HouseholdInvitationsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @alice = users(:alice)
    @household = households(:smith_home)
    sign_in @alice
  end

  def invite(email)
    post household_invitations_path(@household), params: { invitation: { first_name: "Karim", email: email } }
  end

  test "the form renders, for the setup step and on its own" do
    get new_household_invitation_path(@household)
    assert_response :success
    assert_select "h1", 1
    assert_select "a", text: "Inviter plus tard", count: 0

    get new_household_invitation_path(@household, setup: 1)
    assert_response :success
    assert_select "a[href=?]", household_chores_setup_path(@household), text: "Inviter plus tard"
  end

  test "inviting an unknown address sends one email and opens the invitation card" do
    assert_difference "Invitation.count", 1 do
      assert_enqueued_emails 1 do
        invite "newcomer@test.com"
      end
    end

    invitation = Invitation.last
    assert_redirected_to household_invitation_path(@household, invitation)
    assert_equal @alice, invitation.inviter
    assert_equal "Invitation envoyée.", flash[:notice]
    follow_redirect!
    assert_select "h1", "Invitation envoyée"
    assert_select ".pill", "En attente"
    assert_select "a[href=?]", cancel_household_invitation_path(@household, invitation)
    assert_match "0 renvoi sur 2 utilisé", response.body
  end

  test "an address that already has an account goes through an invitation too, never straight in" do
    assert_no_difference "HouseholdMember.count" do
      assert_difference "Invitation.count", 1 do
        invite users(:dana).email
      end
    end
    assert_nil users(:dana).reload.household
    assert_equal "Invitation envoyée.", flash[:notice], "same answer whether or not the address has an account"
  end

  test "an address with an account in another household is invited like any other" do
    assert_difference "Invitation.count", 1 do
      invite users(:carol).email
    end
    assert_equal "Invitation envoyée.", flash[:notice]
  end

  test "own address: a clear message, nothing sent" do
    assert_no_emails do
      assert_no_difference "Invitation.count" do
        invite "alice@test.com"
      end
    end

    assert_response :unprocessable_entity
    assert_field_error "C'est votre propre adresse. Saisissez celle de la personne à inviter."
  end

  test "a member: a clear message naming them" do
    invite users(:bob).email

    assert_response :unprocessable_entity
    assert_field_error "Bob fait déjà partie de ce foyer."
  end

  test "already invited: a clear message with a link to the pending invitation" do
    invite "newcomer@test.com"
    assert_no_difference "Invitation.count" do
      assert_no_enqueued_emails do
        invite "newcomer@test.com"
      end
    end

    assert_response :unprocessable_entity
    assert_field_error(/Une invitation est déjà en attente pour cette adresse depuis le/)
    assert_select "a[href=?]", household_invitation_path(@household, Invitation.last), text: "Voir cette invitation"
  end

  test "household full: a clear message" do
    4.times { |i| @household.invitations.create!(email: "p#{i}@test.com") }

    invite "seventh@test.com"

    assert_response :unprocessable_entity
    assert_select ".alert-box[role=alert]", /Le foyer compte déjà 6 personnes/
  end

  test "incomplete domain and invalid address: clear messages" do
    invite "karim.benali@gmail"
    assert_response :unprocessable_entity
    assert_field_error "Adresse incomplète : il manque la fin du domaine (par exemple gmail.com)."

    invite "karim"
    assert_response :unprocessable_entity
    assert_select "input[aria-invalid=true]"
    assert_select ".field-error"

    invite ""
    assert_field_error "Saisissez l'adresse de la personne à inviter."
  end

  test "the form keeps what was typed when it fails" do
    invite "karim.benali@gmail"

    assert_select "input[type=email][value=?]", "karim.benali@gmail"
  end

  test "the email is in French, carries the token link and says nothing of accounts" do
    invite "newcomer@test.com"
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    invitation = Invitation.last

    assert_equal [ "newcomer@test.com" ], mail.to
    assert_equal "Alice vous invite à rejoindre Smith Home", mail.subject
    html = mail.html_part.body.to_s
    text = mail.text_part.body.to_s
    assert_includes html, invitation_path(invitation.token)
    assert_includes text, invitation_path(invitation.token)
    assert_match "Invitation valable jusqu'au", text
    assert_match "ignorez cet email", text
    assert_no_match(/compte existant|déjà un compte/, text)
  end

  # ---- Resend (B5) ---------------------------------------------------------------

  test "resend: refused before 15 minutes, with the remaining wait shown, then sent with the same token" do
    invite "newcomer@test.com"
    invitation = Invitation.last
    token = invitation.token

    get household_invitation_path(@household, invitation)
    assert_select "[aria-disabled=true]", /Renvoyer · dans 15 min/
    assert_select "form[action=?]", resend_household_invitation_path(@household, invitation), 0

    assert_no_enqueued_emails do
      post resend_household_invitation_path(@household, invitation)
    end
    assert_redirected_to household_invitation_path(@household, invitation)
    assert_match "Réessayez dans 15 min", flash[:alert]

    travel 16.minutes do
      get household_invitation_path(@household, invitation)
      assert_select "form[action=?]", resend_household_invitation_path(@household, invitation)

      assert_enqueued_emails 1 do
        post resend_household_invitation_path(@household, invitation)
      end
      assert_equal "Invitation renvoyée.", flash[:notice]
      assert_equal token, invitation.reload.token
      assert_equal 1, invitation.resend_count
    end
  end

  test "resend: after two resends, the button shows the limit" do
    invite "newcomer@test.com"
    invitation = Invitation.last
    2.times do |i|
      travel_to(Time.current + ((i + 1) * 20).minutes) { post resend_household_invitation_path(@household, invitation) }
    end

    travel_to 2.hours.from_now do
      get household_invitation_path(@household, invitation)
      assert_select "[aria-disabled=true]", "Limite de renvois atteinte"

      assert_no_enqueued_emails do
        post resend_household_invitation_path(@household, invitation)
      end
      assert_match "limite de 2 renvois", flash[:alert]
    end
  end

  test "resend: only the sender sees the button and can use it; everyone else gets a 404" do
    invite "newcomer@test.com"
    invitation = Invitation.last

    travel 16.minutes do
      sign_in users(:bob)
      get household_invitation_path(@household, invitation)
      assert_select "form[action=?]", resend_household_invitation_path(@household, invitation), 0
      assert_select "[aria-disabled=true]", text: /Renvoyer/, count: 0
      assert_match "Seule la personne qui a envoyé", response.body

      assert_no_enqueued_emails do
        post resend_household_invitation_path(@household, invitation)
      end
      assert_response :not_found
      assert_equal 0, invitation.reload.resend_count
    end
  end

  test "resend: the counter survives a cancel and a new invitation" do
    invite "newcomer@test.com"
    first = Invitation.last
    travel_to(20.minutes.from_now) { post resend_household_invitation_path(@household, first) }
    first.reload.cancel!

    travel_to 1.hour.from_now do
      invite "newcomer@test.com"
      second = Invitation.last
      assert_not_equal first, second
      get household_invitation_path(@household, second)
      assert_match "2 renvois sur 2 utilisés", response.body
    end
  end

  # ---- Cancel (B15) ---------------------------------------------------------------

  test "cancelling goes through a confirmation, then the link stops working" do
    invite "newcomer@test.com"
    invitation = Invitation.last

    get cancel_household_invitation_path(@household, invitation)
    assert_response :success
    assert_select "h1", "Annuler cette invitation ?"
    assert_select "[role=alertdialog]", /ne fonctionnera plus/
    assert_select "a[href=?]", household_invitation_path(@household, invitation), text: "Garder"
    assert_predicate invitation.reload, :pending?, "the confirmation page alone cancels nothing"

    delete household_invitation_path(@household, invitation)
    assert_redirected_to household_path(@household)
    assert_equal "Invitation annulée.", flash[:notice]
    assert_predicate invitation.reload, :cancelled?

    sign_out @alice
    get invitation_path(invitation.token)
    assert_response :gone
    assert_select "h1", "Cette invitation n'est plus valable"
  end

  test "after a cancel the address can be invited again" do
    invite "newcomer@test.com"
    delete household_invitation_path(@household, Invitation.last)

    travel 16.minutes do
      assert_difference "Invitation.count", 1 do
        invite "newcomer@test.com"
      end
    end
  end

  # ---- Declined (B13) -----------------------------------------------------------------

  test "when the invitee declines, the household sees « Invitation déclinée » and stays as it was" do
    invite "dana@test.com"
    invitation = Invitation.last
    invitation.decline!(users(:dana))

    get household_invitation_path(@household, invitation)

    assert_response :success
    assert_select "h1", "Invitation déclinée"
    assert_select ".pill", "Déclinée"
    assert_select "p", /Karim n.a pas rejoint le foyer.*votre mise en place est conservée/
    assert_select "a[href=?]", new_household_invitation_path(@household, email: "dana@test.com", first_name: "Karim")
    assert_equal 2, @household.household_members.count

    get household_path(@household)
    assert_select ".pill", "Déclinée"
  end

  test "an expired invitation shows as expired and can be redone" do
    invite "newcomer@test.com"
    invitation = Invitation.last

    travel 15.days do
      get household_invitation_path(@household, invitation)
      assert_select "h1", "Invitation expirée"
      assert_select "a", text: "Inviter de nouveau"
    end
  end

  # ---- Access ---------------------------------------------------------------------------

  test "another household's invitation is a 404" do
    other = Invitation.invite(household: households(:jones_home), email: "x@test.com", inviter: users(:carol), first_name: "Xavier")

    get household_invitation_path(@household, other)
    assert_response :not_found
    sign_in @alice # the 404 request does not keep the session in the test client
    delete household_invitation_path(@household, other)
    assert_response :not_found
    assert_predicate other.reload, :pending?
  end

  test "someone who is not a member cannot reach the household's invitations" do
    sign_in users(:carol)

    get new_household_invitation_path(@household)

    assert_response :not_found
  end

  test "signed out, the household's invitation screens ask for a sign-in" do
    sign_out @alice

    get new_household_invitation_path(@household)

    assert_redirected_to new_user_session_path
  end

  test "sending invitations is rate limited per person" do
    20.times { |i| invite "p#{i}@test.com" }
    assert_no_difference "Invitation.count" do
      invite "one-more@test.com"
    end
    assert_match "Trop d'invitations", flash[:alert]
  end

  test "cancelling an invitation that is no longer pending does not claim it was cancelled" do
    invite "dana@test.com"
    invitation = Invitation.last
    invitation.decline!(users(:dana))

    delete household_invitation_path(@household, invitation)

    assert_redirected_to household_invitation_path(@household, invitation)
    assert_match "il n'y a rien à annuler", flash[:alert]
    assert_not_equal "Invitation annulée.", flash[:notice]
    assert_predicate invitation.reload, :declined?
  end
end
