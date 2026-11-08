require "test_helper"

class SessionTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @alice = users(:alice)
    @alice.update!(password: "password123")
  end

  def sign_in_without_remember_box
    post user_session_path, params: { user: { email: @alice.email, password: "password123" } }
  end

  test "signing in always sets a persistent cookie valid for one week" do
    sign_in_without_remember_box

    assert_redirected_to dashboard_path
    assert cookies["remember_user_token"].present?
    assert_equal 1.week, Devise.remember_for
    assert_in_delta 1.week.from_now, @alice.reload.remember_created_at + 1.week, 5.seconds
  end

  test "the session survives six days with the app closed, and a week of absence ends it" do
    sign_in_without_remember_box

    # "app closed": the session cookie is gone, only the persistent cookie is left
    cookies.delete("_task_balance_session")
    travel 6.days do
      get new_household_path
      assert_redirected_to household_path(households(:smith_home)) # signed in
    end

    # opening the app renewed the week: six more days later, still signed in
    cookies.delete("_task_balance_session")
    travel 12.days do
      get new_household_path
      assert_redirected_to household_path(households(:smith_home))
    end

    # eight days without opening the app: signed out
    cookies.delete("_task_balance_session")
    travel 20.days do
      get dashboard_path
      assert_redirected_to new_user_session_path
    end
  end

  test "wrong credentials give the same generic failure for an unknown address" do
    post user_session_path, params: { user: { email: @alice.email, password: "wrong" } }
    known = [ response.status, flash[:alert] ]
    reset!
    post user_session_path, params: { user: { email: "nobody@test.com", password: "wrong" } }

    assert_equal known, [ response.status, flash[:alert] ]
  end

  test "an unconfirmed account can sign in" do
    dana = users(:dana)
    dana.update!(password: "password123")
    post user_session_path, params: { user: { email: dana.email, password: "password123" } }

    assert_redirected_to dashboard_path
  end

  test "resending the confirmation is generic and rate limited" do
    3.times { post user_confirmation_path, params: { user: { email: users(:dana).email } } }
    assert_no_emails do
      post user_confirmation_path, params: { user: { email: users(:dana).email } }
    end
    assert_redirected_to new_user_confirmation_path

    reset!
    Rails.cache.clear
    post user_confirmation_path, params: { user: { email: "nobody@test.com" } }
    assert_response :redirect
    assert_no_match(/not found|introuvable/i, flash[:alert].to_s)
  end
end
