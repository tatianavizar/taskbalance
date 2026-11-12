require "test_helper"

# Who gets into /admin: only an AdminUser, only after a second factor.
class BackOfficeAccessTest < ActionDispatch::IntegrationTest
  test "signed out, /admin leads to the back-office sign-in" do
    get "/admin"
    assert_redirected_to "/admin/login"
    get "/admin/login"
    assert_response :success
    assert_select "input[name='admin_user[otp_attempt]']"
  end

  test "an app user, signed in, cannot reach /admin or its resources" do
    sign_in users(:alice)
    %w[/admin /admin/users /admin/households /admin/invitations /admin/admin_actions].each do |path|
      get path
      assert_redirected_to "/admin/login", path
    end
    follow_redirect!
    assert_no_match(/alice/i, response.body)
  end

  test "an app user's credentials do not open the back-office sign-in" do
    users(:alice).update!(password: "password123")
    post admin_user_session_path, params: { admin_user: { email: "alice@test.com", password: "password123" } }
    assert_response :unprocessable_entity
    get "/admin"
    assert_redirected_to "/admin/login"
  end

  test "a password alone is refused for an enrolled admin: the code is needed" do
    admin = create_admin
    sign_in_admin(admin, otp: "")
    assert_response :unprocessable_entity
    get "/admin"
    assert_redirected_to "/admin/login"

    sign_in_admin(admin, otp: "000000")
    assert_response :unprocessable_entity
    get "/admin/users"
    assert_redirected_to "/admin/login"
  end

  test "a wrong password is refused even with a valid code" do
    admin = create_admin
    sign_in_admin(admin, password: "not the password")
    assert_response :unprocessable_entity
    get "/admin"
    assert_redirected_to "/admin/login"
  end

  test "a valid password and code open the dashboard" do
    admin = create_admin
    sign_in_admin(admin)
    assert_redirected_to "/admin"
    follow_redirect!
    assert_response :success
    assert_select "h1,h2", text: /Tableau de bord/
  end

  test "a password-only session opened before enrolment does not carry over once the account is enrolled" do
    admin = create_admin(enrolled: false)
    sign_in_admin(admin, otp: "") # session A: password only
    admin.update!(otp_secret: AdminUser.generate_otp_secret, otp_required_for_login: true) # enrolled elsewhere meanwhile
    get "/admin/users"
    assert_redirected_to "/admin/login"
    get "/admin/users"
    assert_redirected_to "/admin/login"
  end

  test "a new admin without the second factor sees nothing but the enrolment page" do
    admin = create_admin(enrolled: false)
    open_enrolment_link(admin)
    sign_in_admin(admin, otp: "")
    assert_redirected_to "/admin"
    follow_redirect!
    assert_redirected_to "/admin/two_factor"

    %w[/admin/users /admin/households /admin/invitations /admin/admin_actions].each do |path|
      get path
      assert_redirected_to "/admin/two_factor", path
    end

    get "/admin/two_factor"
    assert_response :success
    assert_select "[data-test-otp-secret]", text: admin.reload.otp_secret.scan(/.{1,4}/).join(" ")
  end

  test "enrolment: the first code turns the second factor on and opens the back office" do
    admin = create_admin(enrolled: false)
    open_enrolment_link(admin)
    sign_in_admin(admin, otp: "")
    get "/admin/two_factor"

    post "/admin/two_factor", params: { code: "123456" }
    assert_response :unprocessable_entity
    assert_not admin.reload.two_factor_enrolled?
    get "/admin/users"
    assert_redirected_to "/admin/two_factor"

    assert_difference -> { AdminAction.where(action: "two_factor.enrolled").count }, 1 do
      post "/admin/two_factor", params: { code: otp_code(admin) }
    end
    assert_redirected_to "/admin"
    assert admin.reload.two_factor_enrolled?
    get "/admin/users"
    assert_response :success
    get "/admin/two_factor"
    assert_redirected_to "/admin"
  end

  test "after enrolment the next sign-in needs a code" do
    admin = enrol_admin!
    delete destroy_admin_user_session_path

    sign_in_admin(admin, otp: "")
    assert_response :unprocessable_entity
    travel 31.seconds do # a code is accepted once: the next one
      sign_in_admin(admin)
      assert_redirected_to "/admin"
    end
  end

  test "a code can be used only once" do
    admin = create_admin
    code = otp_code(admin)
    sign_in_admin(admin, otp: code)
    assert_redirected_to "/admin"
    delete destroy_admin_user_session_path
    sign_in_admin(admin, otp: code)
    assert_response :unprocessable_entity
  end

  test "five wrong tries lock the account for half an hour" do
    admin = create_admin
    5.times { sign_in_admin(admin, password: "nope") }
    sign_in_admin(admin)
    assert_response :unprocessable_entity
    assert admin.reload.access_locked?
    travel 31.minutes do
      sign_in_admin(admin)
      assert_redirected_to "/admin"
    end
  end

  test "the secret is stored encrypted" do
    admin = create_admin
    raw = AdminUser.connection.select_value("SELECT otp_secret FROM admin_users WHERE id = #{admin.id}")
    assert_not_equal admin.otp_secret, raw
  end

  test "no sign-up and no password-reset page exist" do
    get "/admin/sign_up"
    assert_response :not_found
    get "/admin/password/new"
    assert_response :not_found
    post "/admin"
    assert_response :not_found
  end

  test "an expired admin session is refused" do
    admin = create_admin
    sign_in_admin(admin)
    travel 31.minutes do
      get "/admin/users"
      follow_redirect!
      assert_redirected_to "/admin/login"
    end
  end

  test "the app's own pages do not accept an AdminUser session" do
    admin = create_admin
    sign_in_admin(admin)
    get dashboard_path
    assert_redirected_to new_user_session_path
  end
end
