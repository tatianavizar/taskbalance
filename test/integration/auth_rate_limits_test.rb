require "test_helper"
require "minitest/mock"

# Limits on password guessing and on the endpoints that send account mails
# (decision of 2026-11-08: 3 per hour per address, 9 per hour per connection),
# and what the screens may reveal about an account.
class AuthRateLimitsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @alice = users(:alice)
    @alice.update!(password: "password123")
  end

  def attempt(email, password = "wrong-password")
    post user_session_path, params: { user: { email: email, password: password } }
  end

  # --- Sign-in (finding 1) ---------------------------------------------------

  test "sign-in attempts are throttled per address, with the wrong-password screen" do
    Users::SessionsController::ATTEMPTS_PER_EMAIL.times { attempt(@alice.email) }
    failed = [ response.status, response.body ]

    attempt(@alice.email, "password123") # the right password, over the limit

    assert_equal failed, [ response.status, response.body ]
    assert_select ".alert-box[role=alert]"
    assert_nil session["warden.user.user.key"], "a throttled attempt must not sign in"
    get dashboard_path
    assert_redirected_to new_user_session_path
  end

  test "a throttled unknown address and a throttled known one get the same answer" do
    Users::SessionsController::ATTEMPTS_PER_EMAIL.times { attempt(@alice.email) }
    attempt(@alice.email)
    known = [ response.status, response.body.sub(@alice.email, "EMAIL") ]

    Users::SessionsController::ATTEMPTS_PER_EMAIL.times { attempt("nobody@test.com") }
    attempt("nobody@test.com")
    unknown = [ response.status, response.body.sub("nobody@test.com", "EMAIL") ]

    assert_equal known, unknown
  end

  test "the address is normalised before counting" do
    Users::SessionsController::ATTEMPTS_PER_EMAIL.times { |i| attempt(i.even? ? " ALICE@test.com " : @alice.email) }
    attempt(@alice.email, "password123")

    assert_nil session["warden.user.user.key"]
  end

  test "sign-in attempts are throttled per connection, whatever the address" do
    Users::SessionsController::ATTEMPTS_PER_IP.times { |i| attempt("someone#{i}@test.com") }
    attempt(@alice.email, "password123")

    assert_response :unprocessable_entity
    assert_nil session["warden.user.user.key"]
  end

  test "below the limit the right password still signs in" do
    (Users::SessionsController::ATTEMPTS_PER_EMAIL - 1).times { attempt(@alice.email) }
    attempt(@alice.email, "password123")

    assert_redirected_to dashboard_path
  end

  # --- Password length -------------------------------------------------------

  test "a new password needs 8 characters, an existing shorter one still signs in" do
    assert_equal 8, Devise.password_length.min
    @alice.password = "short12"
    assert_not @alice.valid?

    @alice.update_column(:encrypted_password, Devise::Encryptor.digest(User, "short12"))
    attempt(@alice.email, "short12")
    assert_redirected_to dashboard_path
  end

  # --- Email change (finding 2) ----------------------------------------------

  def change_email(to)
    patch edit_email_path, params: { user: { email: to, current_password: "password123" } }
  end

  test "an email change is limited to 3 per hour per person" do
    sign_in @alice
    3.times { |i| change_email("new#{i}@test.com") }

    assert_no_emails { change_email("new9@test.com") }
    assert_redirected_to edit_email_path
    assert_equal "Trop de demandes. Réessayez dans une heure.", flash[:alert]
    assert_equal "new2@test.com", @alice.reload.unconfirmed_email
  end

  test "an email change is limited to 3 per hour towards the same address" do
    [ users(:bob), users(:carol), users(:dana) ].each do |user|
      user.update!(password: "password123")
      sign_in user
      change_email("victim@test.com")
    end

    @alice.update!(password: "password123")
    sign_in @alice
    assert_no_emails { change_email(" Victim@test.com ") }
    assert_redirected_to edit_email_path
  end

  # --- "Check your emails" screen (finding 3) ---------------------------------

  test "the reset expiry hour is in the default zone, whatever the account's" do
    @alice.update!(time_zone: "Pacific/Auckland")
    travel_to Time.utc(2026, 11, 12, 10, 0) do
      post user_password_path, params: { user: { email: @alice.email } }
      User.stub(:find_by, ->(*) { flunk "the sent screen must not look an account up" }) do
        get sent_user_password_path
      end
    end

    assert_response :success
    expires_at = @controller.instance_variable_get(:@expires_at)
    assert_equal "Europe/Paris", expires_at.time_zone.name
    assert_equal Time.utc(2026, 11, 12, 16, 0), expires_at
  end

  # --- Decided limits (finding 15) --------------------------------------------

  test "password reset: 9 per hour per connection" do
    9.times { |i| post user_password_path, params: { user: { email: "someone#{i}@test.com" } } }
    assert_redirected_to sent_user_password_path

    post user_password_path, params: { user: { email: "one-more@test.com" } }
    assert_redirected_to new_user_password_path
  end

  test "confirmation resend: 9 per hour per connection, 3 per address" do
    9.times { |i| post user_confirmation_path, params: { user: { email: "someone#{i}@test.com" } } }
    assert_redirected_to new_user_session_path

    post user_confirmation_path, params: { user: { email: "one-more@test.com" } }
    assert_redirected_to new_user_confirmation_path
    assert_equal "Trop de demandes. Réessayez dans une heure.", flash[:alert]
  end

  test "sign-up: 9 per hour per connection" do
    9.times do |i|
      post user_registration_path, params: { user: { first_name: "Nina", email: "n#{i}@test.com", password: "password123", password_confirmation: "password123" } }
      reset_session_only
    end
    assert_no_difference "User.count" do
      post user_registration_path, params: { user: { first_name: "Nina", email: "n9@test.com", password: "password123", password_confirmation: "password123" } }
    end
    assert_redirected_to new_user_registration_path
  end

  private

  # A new browser session, same connection (the per-IP counter stays).
  def reset_session_only
    delete destroy_user_session_path
  end
end
