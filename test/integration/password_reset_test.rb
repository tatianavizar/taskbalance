require "test_helper"

class PasswordResetTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def request_reset(email)
    post user_password_path, params: { user: { email: email } }
  end

  def ivar(name)
    @controller.instance_variable_get(name)
  end

  def reset_token_for(user)
    user.send_reset_password_instructions
  end

  test "the answer is the same for a known and an unknown address" do
    request_reset(users(:alice).email)
    known = [ response.status, response.location, flash[:notice] ]
    reset!
    request_reset("nobody@test.com")
    unknown = [ response.status, response.location, flash[:notice] ]

    assert_equal known, unknown
  end

  test "only a known address receives a mail" do
    assert_emails(1) { request_reset(users(:alice).email) }
    assert_no_emails { request_reset("nobody@test.com") }
  end

  test "a valid link exposes the account email and no expired state" do
    token = reset_token_for(users(:alice))

    get edit_user_password_path(reset_password_token: token)

    assert_response :success
    assert_equal false, ivar(:@reset_link_expired)
    assert_equal users(:alice).email, ivar(:@reset_email)
  end

  test "an expired link renders the expired state with the date it was sent" do
    token = reset_token_for(users(:alice))
    sent_at = users(:alice).reload.reset_password_sent_at

    travel 7.hours do
      get edit_user_password_path(reset_password_token: token)
    end

    assert_response :success
    assert_equal true, ivar(:@reset_link_expired)
    assert_in_delta sent_at, ivar(:@reset_link_sent_at), 1.second
    assert_nil ivar(:@reset_email)
  end

  test "an unknown or already used token renders the expired state without a date" do
    get edit_user_password_path(reset_password_token: "nonsense")
    assert_equal true, ivar(:@reset_link_expired)
    assert_nil ivar(:@reset_link_sent_at)

    token = reset_token_for(users(:alice))
    put user_password_path, params: { user: { reset_password_token: token, password: "newpassword1", password_confirmation: "newpassword1" } }
    reset!
    get edit_user_password_path(reset_password_token: token)
    assert_equal true, ivar(:@reset_link_expired)
  end

  test "submitting an expired token does not change the password and shows the expired state" do
    token = reset_token_for(users(:alice))
    old = users(:alice).reload.encrypted_password

    travel 7.hours do
      put user_password_path, params: { user: { reset_password_token: token, password: "newpassword1", password_confirmation: "newpassword1" } }
    end

    assert_response :unprocessable_entity
    assert_equal true, ivar(:@reset_link_expired)
    assert_equal old, users(:alice).reload.encrypted_password
  end

  test "a valid token changes the password" do
    token = reset_token_for(users(:alice))
    put user_password_path, params: { user: { reset_password_token: token, password: "newpassword1", password_confirmation: "newpassword1" } }
    assert users(:alice).reload.valid_password?("newpassword1")
  end

  test "reset requests are rate limited per address" do
    3.times { request_reset(users(:alice).email) }
    assert_no_emails do
      request_reset(users(:alice).email)
    end
    assert_redirected_to new_user_password_path
    assert_predicate flash[:alert], :present?
  end

  test "reset requests are rate limited per IP, known or not" do
    5.times { |i| request_reset("someone#{i}@test.com") }
    request_reset("one-more@test.com")
    assert_redirected_to new_user_password_path
    assert_predicate flash[:alert], :present?
  end
end
