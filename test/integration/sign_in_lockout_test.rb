require "test_helper"

# Account lockout after wrong passwords (SignInLockout, decision of
# 2026-11-13): 4 in 2 hours lock for 2 hours, the 3rd lock waits for the
# team, a success resets everything, the screen never tells, the owner gets
# an email.
class SignInLockoutTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @alice = users(:alice)
    @alice.update!(password: "password123")
  end

  def attempt(password = "wrong-password", email: @alice.email)
    post user_session_path, params: { user: { email: email, password: password } }
  end

  def signed_in?
    session["warden.user.user.key"].present?
  end

  def lock_out!(times = SignInLockout::MAX_FAILED_ATTEMPTS)
    times.times { attempt }
  end

  test "4 wrong passwords within 2 hours lock the account for 2 hours, the right one included" do
    travel_to Time.zone.local(2026, 11, 12, 10, 0) do
      lock_out!(3)
      attempt("password123")
      assert signed_in?, "3 wrong passwords do not lock"
    end
    delete destroy_user_session_path

    travel_to Time.zone.local(2026, 11, 12, 11, 0) do
      lock_out!
      assert @alice.reload.sign_in_temporarily_locked?
      assert_equal 1, @alice.sign_in_lockouts_count

      attempt("password123")
      assert_not signed_in?
      assert_response :unprocessable_entity
    end

    travel_to Time.zone.local(2026, 11, 12, 12, 59) do
      attempt("password123")
      assert_not signed_in?, "still locked 1 h 59 later"
    end

    travel_to Time.zone.local(2026, 11, 12, 13, 1) do
      attempt("password123")
      assert signed_in?, "the lock lapses after 2 hours"
      assert_equal [ 0, nil ], [ @alice.reload.sign_in_lockouts_count, @alice.sign_in_locked_at ]
    end
  end

  test "wrong passwords older than 2 hours stop counting" do
    travel_to(Time.zone.local(2026, 11, 12, 8, 0)) { lock_out!(2) }
    travel_to(Time.zone.local(2026, 11, 12, 9, 30)) { lock_out!(1) }
    travel_to Time.zone.local(2026, 11, 12, 10, 15) do
      attempt # 4th in all, 2nd within 2 hours
      assert_not @alice.reload.sign_in_locked?
      assert_equal 2, @alice.failed_sign_ins_at.size
      attempt
      assert_not @alice.reload.sign_in_locked?, "5 in all, 3 within 2 hours"
      attempt
      assert @alice.reload.sign_in_locked?
    end
  end

  test "attempts during a lock do not count; the 3rd lock is permanent until the team unlocks" do
    start = Time.zone.local(2026, 11, 12, 8, 0)
    2.times do |round|
      travel_to(start + (round * 3).hours) do
        lock_out!
        5.times { attempt } # while locked: ignored
      end
    end
    assert_equal 2, @alice.reload.sign_in_lockouts_count
    assert_not @alice.sign_in_hard_locked?

    travel_to(start + 6.hours) { lock_out! }
    assert @alice.reload.sign_in_hard_locked?
    assert_equal 3, @alice.sign_in_lockouts_count

    travel_to(start + 30.days) do
      attempt("password123")
      assert_not signed_in?, "a permanent lock does not lapse"
    end
  end

  test "a successful sign-in resets both counters" do
    lock_out!(3)
    @alice.reload.update_columns(sign_in_lockouts_count: 2)
    attempt("password123")
    assert signed_in?
    @alice.reload
    assert_equal [], @alice.failed_sign_ins_at
    assert_equal 0, @alice.sign_in_lockouts_count
  end

  test "the screen of a locked account is the screen of a wrong password, and of an unknown address" do
    lock_out!(3)
    attempt
    wrong = [ response.status, response.body.sub(@alice.email, "EMAIL") ]

    attempt("password123") # locked now, right password
    locked = [ response.status, response.body.sub(@alice.email, "EMAIL") ]

    attempt(email: "nobody@test.com")
    unknown = [ response.status, response.body.sub("nobody@test.com", "EMAIL") ]

    assert_equal wrong, locked
    assert_equal wrong, unknown
    assert_select ".alert-box[role=alert]"
    assert_no_match(/bloqu/i, response.body)
  end

  test "the owner gets an email at each lock: when it reopens, then whom to write to" do
    @alice.update!(time_zone: "Europe/Paris")
    travel_to Time.zone.local(2026, 11, 12, 10, 0) do
      assert_enqueued_emails(1) { lock_out! }
    end
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @alice.email ], mail.to
    assert_equal "Connexion à votre compte 50/50 bloquée pendant 2 heures", mail.subject
    assert_includes mail.text_part.body.to_s, "4 mots de passe incorrects"
    assert_includes mail.text_part.body.to_s, "jusqu'au 12 novembre à 13:00"
    assert_includes mail.html_part.body.to_s, "jusqu&#39;au 12 novembre à 13:00"

    @alice.reload.update_columns(sign_in_lockouts_count: 2, sign_in_locked_at: 3.hours.ago)
    ActionMailer::Base.deliveries.clear
    assert_enqueued_emails(1) { lock_out! }
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Connexion à votre compte 50/50 bloquée", mail.subject
    assert_includes mail.text_part.body.to_s, "troisième blocage"
    assert_includes mail.text_part.body.to_s, "bonjour@cinquante.app"
  end

  test "an unknown address never sends an email nor writes anything" do
    assert_no_enqueued_emails { 6.times { attempt(email: "nobody@test.com") } }
  end

  test "a password reset changes the password but does not lift the lock nor sign in" do
    lock_out!
    token = @alice.send_reset_password_instructions
    put user_password_path, params: { user: { reset_password_token: token, password: "brand-new-pass", password_confirmation: "brand-new-pass" } }
    assert_redirected_to new_user_session_path
    assert_not signed_in?
    assert_match(/reste bloquée/, flash[:notice])
    assert @alice.reload.valid_password?("brand-new-pass")
    assert @alice.sign_in_locked?
  end

  test "a password reset on an open account still signs in" do
    lock_out!(2)
    token = @alice.send_reset_password_instructions
    put user_password_path, params: { user: { reset_password_token: token, password: "brand-new-pass", password_confirmation: "brand-new-pass" } }
    assert signed_in?
    assert_equal [], @alice.reload.failed_sign_ins_at
  end

  test "a session already open stays open during a lock" do
    lock_out!
    assert @alice.reload.sign_in_locked?
    sign_in @alice # the session of another device, opened before the lock
    get dashboard_path
    assert_response :success
  end
end
