require "test_helper"

class RegistrationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def sign_up(email: "nina@test.com", first_name: "Nina", password: "password123")
    post user_registration_path, params: { user: {
      email: email, first_name: first_name, password: password, password_confirmation: password
    } }
  end

  test "sign-up creates an unconfirmed account, signs in and sends the confirmation" do
    assert_difference "User.count", 1 do
      assert_emails 1 do
        sign_up
      end
    end

    user = User.find_by!(email: "nina@test.com")
    assert_equal "Nina", user.first_name
    assert_not user.confirmed?
    assert_response :redirect
    # not blocked: the new household screen opens without confirming
    get new_household_path
    assert_response :success
  end

  test "the first name is required at sign-up" do
    assert_no_difference "User.count" do
      sign_up(first_name: "")
    end
    assert_response :unprocessable_entity
  end

  test "an unconfirmed account can create a household" do
    sign_up
    assert_difference "Household.count", 1 do
      post households_path, params: { household: { name: "Chez Nina" } }
    end
  end

  test "following the confirmation link confirms the account" do
    sign_up
    user = User.find_by!(email: "nina@test.com")
    mail = ActionMailer::Base.deliveries.last
    token = mail.body.to_s[/confirmation_token=([^"&\s]+)/, 1]
    assert token, "the mail must carry a confirmation link"

    get user_confirmation_path(confirmation_token: token)

    assert user.reload.confirmed?
  end

  test "a confirmation link older than 24 hours is refused" do
    sign_up
    user = User.find_by!(email: "nina@test.com")
    token = ActionMailer::Base.deliveries.last.body.to_s[/confirmation_token=([^"&\s]+)/, 1]

    travel 25.hours do
      get user_confirmation_path(confirmation_token: token)
    end

    assert_not user.reload.confirmed?
  end

  test "sign-up with a known email looks like a success and mails the owner" do
    existing = users(:alice)

    assert_no_difference "User.count" do
      assert_enqueued_emails 1 do
        sign_up(email: existing.email)
      end
    end

    assert_redirected_to new_user_session_path
    assert_predicate flash[:notice], :present?
    assert_not flash[:alert]
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ existing.email ], mail.to
    assert_not_includes mail.to, "nina@test.com"
  end

  test "known email is matched whatever its case, and still validates the rest" do
    assert_no_difference "User.count" do
      sign_up(email: "ALICE@test.com")
    end
    assert_redirected_to new_user_session_path

    sign_up(email: users(:alice).email, password: "x")
    assert_response :unprocessable_entity # same error a new address would get
  end

  test "sign-up through a valid invitation confirms the account and joins the household" do
    household = households(:smith_home)
    invitation = Invitation.create!(email: "guest@test.com", household: household)

    get new_user_registration_path(invitation_token: invitation.token)
    assert_no_emails do
      sign_up(email: "guest@test.com", first_name: "Gus")
    end

    user = User.find_by!(email: "guest@test.com")
    assert user.confirmed?
    assert_equal household, user.household
    assert user.household_membership.member?
    assert_not Invitation.exists?(invitation.id)
  end

  test "an invitation token for another address does not confirm the account" do
    invitation = Invitation.create!(email: "guest@test.com", household: households(:smith_home))

    get new_user_registration_path(invitation_token: invitation.token)
    assert_emails 1 do
      sign_up(email: "someone-else@test.com")
    end

    user = User.find_by!(email: "someone-else@test.com")
    assert_not user.confirmed?
    assert_nil user.household
  end

  test "sign-up is rate limited per address and per IP" do
    3.times { reset!; sign_up(email: "spam@test.com") }
    reset!
    assert_no_emails do
      sign_up(email: "spam@test.com")
    end
    assert_redirected_to new_user_registration_path

    Rails.cache.clear
    10.times { |i| reset!; sign_up(email: "user#{i}@test.com") }
    reset!
    assert_no_difference "User.count" do
      sign_up(email: "one-more@test.com")
    end
    assert_redirected_to new_user_registration_path
  end

  test "the account can be edited with a first name" do
    users(:alice).update!(password: "password123")
    sign_in users(:alice)
    put user_registration_path, params: { user: { first_name: "Alicia", current_password: "password123" } }
    assert_equal "Alicia", users(:alice).reload.first_name
  end
end
