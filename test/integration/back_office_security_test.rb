require "test_helper"

# Regression tests for the security review of the back office (lot 9).
class BackOfficeSecurityTest < ActionDispatch::IntegrationTest
  EMAIL_CELL = "td.col-email"

  def emails_listed
    css_select(EMAIL_CELL).map { |cell| cell.text.squish }
  end

  # ---- 1 and 6. Enrolment is delivered out of band ---------------------------

  test "1. the password alone never shows the secret" do
    admin = create_admin(enrolled: false)
    secret = admin.reload.otp_secret
    sign_in_admin(admin, otp: "")
    get "/admin/two_factor"
    assert_response :forbidden
    assert_select "[data-test-link-required]"
    assert_not_includes response.body, secret
    assert_select "[data-test-otp-secret]", count: 0
  end

  test "1. and 6. without the link a code is refused, with no 500, even a valid one" do
    admin = create_admin(enrolled: false)
    sign_in_admin(admin, otp: "")
    post "/admin/two_factor", params: { code: otp_code(admin) }
    assert_response :forbidden
    assert_not admin.reload.two_factor_enrolled?
  end

  test "6. a POST before any GET does not fail when there is no secret" do
    admin = create_admin(enrolled: false)
    admin.update_columns(otp_secret: nil) # an account from before the link existed
    assert_not admin.enrol!("123456")
    open_enrolment_link(admin)
    sign_in_admin(admin, otp: "")
    post "/admin/two_factor", params: { code: "123456" }
    assert_response :unprocessable_entity
  end

  test "1. the link alone, without the password, shows nothing" do
    admin = create_admin(enrolled: false)
    open_enrolment_link(admin)
    assert_redirected_to "/admin/two_factor"
    get "/admin/two_factor"
    assert_redirected_to "/admin/login"
  end

  test "1. the whole path works: link, password, secret, first code" do
    admin = create_admin(enrolled: false)
    open_enrolment_link(admin)
    sign_in_admin(admin, otp: "")
    follow_redirect! # /admin
    follow_redirect! # /admin/two_factor
    assert_response :success
    assert_select "[data-test-otp-secret]"
    post "/admin/two_factor", params: { code: otp_code(admin) }
    assert_redirected_to "/admin"
    assert admin.reload.two_factor_enrolled?
  end

  test "1. a link belongs to one admin" do
    first = create_admin(enrolled: false)
    other = create_admin(enrolled: false, email: "other@cinquante.test")
    open_enrolment_link(other, token: enrolment_token(first))
    sign_in_admin(other, otp: "")
    get "/admin/two_factor"
    assert_response :forbidden
  end

  test "1. a link expires after 30 minutes" do
    admin = create_admin(enrolled: false)
    open_enrolment_link(admin)
    sign_in_admin(admin, otp: "")
    travel 31.minutes do
      get "/admin/two_factor"
      assert_response :forbidden
    end
  end

  test "1. a link is single use: once enrolled it is dead, and so is any older link" do
    admin = create_admin(enrolled: false)
    token = enrolment_token(admin)
    assert_equal admin, AdminUser.find_by_token_for(:enrolment, token)

    enrol_admin!(admin)
    assert_nil AdminUser.find_by_token_for(:enrolment, token)

    newer = admin.reload.issue_enrolment!
    assert_equal admin, AdminUser.find_by_token_for(:enrolment, newer)
    assert_nil AdminUser.find_by_token_for(:enrolment, token)
  end

  test "1. each link comes with a fresh secret, and issuing one kills the previous link" do
    admin = create_admin(enrolled: false)
    old_token = enrolment_token(admin)
    old_secret = admin.reload.otp_secret
    new_token = admin.issue_enrolment!
    assert_not_equal old_secret, admin.otp_secret
    assert_nil AdminUser.find_by_token_for(:enrolment, old_token)
    assert_equal admin, AdminUser.find_by_token_for(:enrolment, new_token)
  end

  test "1. resetting the second factor ends every session of that admin" do
    admin = create_admin
    sign_in_admin(admin)
    get "/admin/users"
    assert_response :success

    result = BackOffice::Console.reset_two_factor(email: admin.email)
    assert_predicate result, :enrolment_issued?
    assert_not admin.reload.two_factor_enrolled?
    get "/admin/users"
    assert_redirected_to "/admin/login"
    get "/admin/two_factor"
    assert_redirected_to "/admin/login"
  end

  test "1. a password reset ends sessions too" do
    admin = create_admin
    sign_in_admin(admin)
    BackOffice::Console.bootstrap(email: admin.email, password: "another long password")
    get "/admin/users"
    assert_redirected_to "/admin/login"
  end

  test "1. the printed link opens the enrolment" do
    admin = create_admin(enrolled: false)
    token = admin.issue_enrolment!
    url = BackOffice::Console.enrolment_url(token)
    assert_match(%r{\Ahttp://localhost:3000/admin/two_factor/link/}, url)
    assert_equal admin, AdminUser.find_by_token_for(:enrolment, url.split("/").last)
  end

  # ---- 2. is covered in back_office_actions_test.rb --------------------------

  # ---- 3. Sorting ------------------------------------------------------------

  test "3. an order outside the allowlist falls back to the default order" do
    sign_in_team!
    users(:bob).household_membership.update!(empty_weeks_streak: 9)
    get "/admin/users"
    default = emails_listed
    assert_operator default.size, :>, 2

    [ "household_members.empty_weeks_streak_desc", "household_members.empty_weeks_streak_asc",
      "users.encrypted_password_asc", "users.reset_password_token_desc", "encrypted_password_desc",
      "nonexistent_table.x_asc", "nonexistent_column_desc", "email_asc; DROP TABLE users", "..." ].each do |order|
      get "/admin/users", params: { order: order }
      assert_response :success, order
      assert_equal default, emails_listed, order
    end
  end

  test "3. an allowed column still sorts" do
    sign_in_team!
    get "/admin/users", params: { order: "email_asc" }
    assert_equal emails_listed.sort, emails_listed
    get "/admin/users", params: { order: "email_desc" }
    assert_equal emails_listed.sort.reverse, emails_listed
  end

  test "3. invitations cannot be sorted by token, nor Ransack's q[s]" do
    sign_in_team!
    household = households(:smith_home)
    %w[a b c].each { |n| Invitation.invite(household: household, email: "#{n}@example.com", inviter: users(:alice), first_name: n.upcase) }
    get "/admin/invitations"
    default = css_select("td.col-email").map { |c| c.text.squish }
    [ { order: "invitations.token_asc" }, { order: "token_desc" }, { q: { s: "token asc" } }, { q: { s: "households.name asc" } },
      { q: { s: [ "email asc", "token desc" ] } } ].each do |params|
      get "/admin/invitations", params: params
      assert_response :success, params.inspect
      assert_equal default, css_select("td.col-email").map { |c| c.text.squish }, params.inspect
    end
  end

  test "3. every resource declares its own list, and a resource that declares none cannot be sorted" do
    controllers = ActiveAdmin.application.namespaces[:admin].resources.select { |r| r.respond_to?(:controller) }.map(&:controller)
    assert_not_empty controllers
    controllers.each do |controller|
      assert_includes controller.ancestors, BackOfficeSortable, controller.name
      assert_no_match(/token|password|empty_weeks|\./, controller.sortable_column_names.join(" "), controller.name)
    end
    assert_empty ActiveAdmin::BaseController.sortable_column_names
  end

  # ---- 4. Last activity -------------------------------------------------------

  test "4. last activity: nothing for a household of one, an ISO week for two or more, never sortable" do
    sign_in_team!
    solo = Household.create_for(users(:dana), name: "Dana seule")
    ChoreLog.create!(user: users(:dana), household: solo, chore_name: "Seule", category: "other", mental_load: true,
                     execution_load: true, time_spent: 5, completed_at: Time.zone.local(2026, 11, 3, 10))
    smith = households(:smith_home)
    ChoreLog.create!(user: users(:alice), chore: chores(:smith_custom), household: smith, mental_load: true,
                     execution_load: false, time_spent: 5, completed_at: Time.zone.local(2026, 11, 5, 10))

    get "/admin/households"
    rows = css_select("tr").to_h { |tr| [ tr.at_css("td")&.text&.squish, tr.css("td").map { |td| td.text.squish } ] }
    assert_includes rows["Dana seule"], "—"
    assert_not_includes rows["Dana seule"].join(" "), "semaine"
    assert_includes rows["Smith Home"], "semaine 45"
    assert_not_includes response.body, "3 novembre"

    get "/admin/households"
    default = css_select("td.col-name").map { |c| c.text.squish }
    [ "last_activity_at_asc", "last_activity_at_desc", "member_count_desc" ].each do |order|
      get "/admin/households", params: { order: order }
      assert_equal default, css_select("td.col-name").map { |c| c.text.squish }, order
    end
  end

  # ---- 5. Enrolment failures count on the account -----------------------------

  test "5. five wrong enrolment codes lock the account, from any address" do
    admin = create_admin(enrolled: false)
    open_enrolment_link(admin)
    sign_in_admin(admin, otp: "")
    get "/admin/two_factor"

    4.times do |i|
      post "/admin/two_factor", params: { code: "00000#{i}" }, headers: { "REMOTE_ADDR" => "10.0.0.#{i}" }
      assert_response :unprocessable_entity
    end
    assert_equal 4, admin.reload.failed_attempts
    post "/admin/two_factor", params: { code: "000009" }, headers: { "REMOTE_ADDR" => "10.0.0.9" }
    assert_redirected_to "/admin/login"
    assert_predicate admin.reload, :access_locked?
    assert_equal 5, AdminAction.where(action: "two_factor.enrolment_failed").count
    assert_equal 1, AdminAction.where(action: "admin.locked").count

    get "/admin/two_factor"
    assert_redirected_to "/admin/login"
    sign_in_admin(admin, otp: "")
    assert_response :unprocessable_entity
  end

  test "5. a good code resets the failure count" do
    admin = create_admin(enrolled: false)
    open_enrolment_link(admin)
    sign_in_admin(admin, otp: "")
    get "/admin/two_factor"
    2.times { post "/admin/two_factor", params: { code: "000000" } }
    assert_equal 2, admin.reload.failed_attempts
    post "/admin/two_factor", params: { code: otp_code(admin) }
    assert_equal 0, admin.reload.failed_attempts
  end

  # ---- 7. Console writes are logged; passwords; sign-ins are logged -----------

  test "7. the console tasks write AdminAction rows with the actor console" do
    result = BackOffice::Console.bootstrap(email: "new@cinquante.test", password: "a long enough password")
    entry = AdminAction.order(:id).last
    assert_equal [ "admin.bootstrapped", "console", result.admin.id ], [ entry.action, entry.admin_email, entry.record_id ]
    assert_nil entry.admin_user_id
    assert_equal true, entry.detail["enrolment_link_issued"]

    BackOffice::Console.bootstrap(email: "new@cinquante.test", password: "another long password")
    assert_equal "admin.password_reset", AdminAction.order(:id).last.action

    BackOffice::Console.reset_two_factor(email: "new@cinquante.test")
    last = AdminAction.order(:id).last
    assert_equal [ "admin.two_factor_reset", "console" ], [ last.action, last.admin_email ]
  end

  test "7. the password rules" do
    weak = [ "short", "aaaaaaaaaaaaaaaa", "abababababab", "password1234", "Administrator", "team-cinquante-1", "123456789012" ]
    weak.each do |password|
      admin = AdminUser.new(email: "team@cinquante.test", password: password, password_confirmation: password)
      assert_not admin.valid?, "#{password} should be refused"
    end
    good = AdminUser.new(email: "team@cinquante.test", password: "correct horse battery", password_confirmation: "correct horse battery")
    assert good.valid?, good.errors.full_messages.to_sentence
  end

  class FakeTerminal
    def initialize(*lines) = @lines = lines
    def tty? = true
    def noecho = yield(self)
    def gets = @lines.shift
  end

  test "7. the password is asked on the terminal, twice, without echo; ENV is a warned fallback" do
    output = StringIO.new
    assert_equal "typed password here", AdminTasks.read_password(input: FakeTerminal.new("typed password here\n", "typed password here\n"), output: output, env: {})
    assert_not_includes output.string, "typed password here"

    assert_raises(SystemExit) do
      capture_io { AdminTasks.read_password(input: FakeTerminal.new("one one one one\n", "two two two two\n"), output: StringIO.new, env: {}) }
    end

    output = StringIO.new
    assert_equal "from the env", AdminTasks.read_password(input: StringIO.new, output: output, env: { "ADMIN_PASSWORD" => "from the env" })
    assert_match(/Warning: the password comes from ADMIN_PASSWORD/, output.string)

    assert_raises(SystemExit) { capture_io { AdminTasks.read_password(input: StringIO.new, output: StringIO.new, env: {}) } }
  end

  test "7. sign-ins, refused sign-ins and lockouts are in the journal" do
    admin = create_admin
    sign_in_admin(admin)
    signed_in = AdminAction.find_by!(action: "admin.signed_in")
    assert_equal [ admin.id, admin.email ], [ signed_in.admin_user_id, signed_in.admin_email ]
    assert_equal true, signed_in.detail["two_factor"]
    assert signed_in.detail["ip"].present?
    delete destroy_admin_user_session_path

    sign_in_admin(admin, otp: "000000")
    failed = AdminAction.find_by!(action: "admin.sign_in_failed")
    assert_equal admin.id, failed.admin_user_id
    assert_equal admin.email, failed.admin_email

    sign_in_admin(AdminUser.new(email: "nobody@cinquante.test"), otp: "000000")
    unknown = AdminAction.where(action: "admin.sign_in_failed").order(:id).last
    assert_nil unknown.admin_user_id
    assert_equal "nobody@cinquante.test", unknown.admin_email

    4.times { sign_in_admin(admin, password: "wrong password") }
    assert_operator AdminAction.where(action: "admin.locked").count, :>=, 1
    assert_predicate admin.reload, :access_locked?
  end

  test "7. a visit to /admin without a session is not logged as a failed sign-in" do
    assert_no_difference "AdminAction.count" do
      get "/admin"
    end
  end

  # ---- 8. The journal is append-only in the database --------------------------

  def an_entry
    AdminAction.record_console!(action: "admin.bootstrapped")
  end

  test "8. the database refuses to update, delete or truncate the journal" do
    entry = an_entry
    connection = AdminAction.connection
    [ "UPDATE admin_actions SET action = 'admin.locked'",
      "UPDATE admin_actions SET detail = '{}' WHERE id = #{entry.id}",
      "DELETE FROM admin_actions",
      "TRUNCATE admin_actions" ].each do |sql|
      error = assert_raises(ActiveRecord::StatementInvalid, sql) do
        AdminAction.transaction(requires_new: true) { connection.execute(sql) }
      end
      assert_match(/append-only/, error.message)
    end
    assert_raises(ActiveRecord::StatementInvalid) { AdminAction.transaction(requires_new: true) { AdminAction.delete_all } }
    assert_raises(ActiveRecord::StatementInvalid) { AdminAction.transaction(requires_new: true) { AdminAction.update_all(action: "x") } }
    assert AdminAction.exists?(entry.id)
    assert_equal "admin.bootstrapped", entry.reload.action
  end

  test "8. destroying an admin is refused by the model and by the foreign key" do
    admin = create_admin
    AdminAction.record!(admin: admin, action: "admin.signed_in", record: admin)
    assert_raises(ActiveRecord::DeleteRestrictionError) { admin.destroy }
    assert_raises(ActiveRecord::InvalidForeignKey) do
      AdminUser.transaction(requires_new: true) { AdminUser.connection.execute("DELETE FROM admin_users WHERE id = #{admin.id}") }
    end
    assert_equal 1, AdminAction.where(admin_user_id: admin.id).count
  end

  # ---- 9. Absolute session lifetime -------------------------------------------

  test "9. an active session still ends 8 hours after sign-in" do
    admin = create_admin
    start = Time.current
    travel_to(start) { sign_in_admin(admin) }

    (1..16).each do |step| # every 29 minutes: never idle for 30
      travel_to(start + (step * 29).minutes) do
        get "/admin/users"
        assert_response :success, "step #{step}"
      end
    end
    travel_to(start + 17 * 29.minutes) do # 8 h 13 min
      get "/admin/users"
      follow_redirect! if response.redirect? && response.location.end_with?("/admin/users")
      assert_redirected_to "/admin/login"
    end
  end

  test "9. the idle timeout is still 30 minutes" do
    sign_in_team!
    travel 31.minutes do
      get "/admin/users"
      follow_redirect! if response.redirect? && response.location.end_with?("/admin/users")
      assert_redirected_to "/admin/login"
    end
  end
end
