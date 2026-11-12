require "test_helper"
require "minitest/mock"

# Limits on password guessing and on the endpoints that send account mails
# (decisions of 2026-11-08 and 2026-11-13), and what the screens may reveal
# about an account. The per-account lockout is in sign_in_lockout_test.rb.
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

  test "sign-in attempts are throttled per connection, whatever the address" do
    Users::SessionsController::ATTEMPTS_PER_IP.times { |i| attempt("someone#{i}@test.com") }
    attempt(@alice.email, "password123")

    assert_response :unprocessable_entity
    assert_nil session["warden.user.user.key"]
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

  test "an email change is limited to 2 per account over a rolling 24 hours" do
    sign_in @alice
    travel_to Time.zone.local(2026, 11, 12, 9, 0) do
      change_email("new0@test.com")
    end
    travel_to Time.zone.local(2026, 11, 12, 20, 0) do
      change_email("new1@test.com")
      assert_equal "new1@test.com", @alice.reload.unconfirmed_email

      assert_no_emails { change_email("new2@test.com") }
      assert_redirected_to edit_email_path
      assert_equal "new1@test.com", @alice.reload.unconfirmed_email

      get edit_email_path
      assert_select "[data-test=email-change-limit]", text: /2 fois en 24 heures.*13 novembre à 10:00/
      assert_select "input[name='user[email]']", count: 0
    end
    # 24 hours after the first change, one is free again; the window slides.
    travel_to Time.zone.local(2026, 11, 13, 9, 1) do
      change_email("new3@test.com")
      assert_equal "new3@test.com", @alice.reload.unconfirmed_email
      assert_no_emails { change_email("new4@test.com") }
    end
  end

  test "a refused email change (wrong password) does not count" do
    sign_in @alice
    3.times { patch edit_email_path, params: { user: { email: "x@test.com", current_password: "nope" } } }
    change_email("new0@test.com")
    change_email("new1@test.com")
    assert_equal "new1@test.com", @alice.reload.unconfirmed_email
    assert_equal 2, @alice.recent_email_changes.size
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
