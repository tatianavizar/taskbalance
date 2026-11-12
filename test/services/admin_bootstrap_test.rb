require "test_helper"
require "rake"

# `bin/rails admin:bootstrap` and `admin:reset_two_factor` (lib/tasks/admin.rake).
# Tests have no terminal, so the password comes from the ENV fallback.
class AdminBootstrapTest < ActiveSupport::TestCase
  PASSWORD = "a long enough password".freeze

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:bootstrap")
    @env = ENV.to_h.slice("ADMIN_EMAIL", "ADMIN_PASSWORD", "ROLE")
    @stdin = $stdin
    $stdin = StringIO.new
  end

  teardown do
    $stdin = @stdin
    ENV.delete("ADMIN_EMAIL")
    ENV.delete("ADMIN_PASSWORD")
    ENV.delete("ROLE")
    @env.each { |key, value| ENV[key] = value }
  end

  def run_task(name)
    task = Rake::Task[name]
    task.reenable
    capture_io { task.invoke }
  end

  test "creates the first admin, not enrolled, prints the one-time link and warns about the ENV password" do
    ENV["ADMIN_EMAIL"] = " Team@Cinquante.test "
    ENV["ADMIN_PASSWORD"] = PASSWORD

    out = nil
    err = nil
    assert_difference "AdminUser.count", 1 do
      out, err = run_task("admin:bootstrap")
    end
    admin = AdminUser.find_by!(email: "team@cinquante.test")
    assert admin.valid_password?(PASSWORD)
    assert_not admin.two_factor_enrolled?
    assert_match(%r{/admin/two_factor/link/}, out)
    assert_match(/Warning: the password comes from ADMIN_PASSWORD/, err)
    token = out[%r{/admin/two_factor/link/(\S+)}, 1]
    assert_equal admin, AdminUser.find_by_token_for(:enrolment, token)
    assert_equal "console", AdminAction.find_by!(action: "admin.bootstrapped").admin_email
    assert admin.superadmin?, "the first account manages the others"
    assert_equal "superadmin", AdminAction.find_by!(action: "admin.bootstrapped").detail["role"]
  end

  test "ROLE=admin creates a plain admin; an existing account keeps its role unless ROLE is given" do
    ENV["ADMIN_EMAIL"] = "plain@cinquante.test"
    ENV["ADMIN_PASSWORD"] = PASSWORD
    ENV["ROLE"] = "admin"
    run_task "admin:bootstrap"
    admin = AdminUser.find_by!(email: "plain@cinquante.test")
    assert admin.admin?

    ENV.delete("ROLE")
    run_task "admin:bootstrap"
    assert admin.reload.admin?

    ENV["ROLE"] = "superadmin"
    run_task "admin:bootstrap"
    assert admin.reload.superadmin?
    assert_equal "superadmin", AdminAction.order(:id).last.detail["role"]
  end

  test "an unknown ROLE is refused before anything is written" do
    ENV["ADMIN_EMAIL"] = "team@cinquante.test"
    ENV["ADMIN_PASSWORD"] = PASSWORD
    ENV["ROLE"] = "owner"
    assert_raises(SystemExit) { capture_io { run_task "admin:bootstrap" } }
    assert_equal 0, AdminUser.count
  end

  test "running it again resets the password, creates nobody, and leaves an enrolled second factor alone" do
    ENV["ADMIN_EMAIL"] = "team@cinquante.test"
    ENV["ADMIN_PASSWORD"] = PASSWORD
    run_task "admin:bootstrap"
    admin = AdminUser.find_by!(email: "team@cinquante.test")
    admin.update!(otp_required_for_login: true)

    ENV["ADMIN_PASSWORD"] = "another long password"
    out = nil
    assert_no_difference "AdminUser.count" do
      out, = run_task("admin:bootstrap")
    end
    assert admin.reload.valid_password?("another long password")
    assert admin.two_factor_enrolled?
    assert_no_match(%r{/admin/two_factor/link/}, out)
    assert_equal "admin.password_reset", AdminAction.order(:id).last.action
  end

  test "refuses a weak password and a missing ENV, and writes nothing" do
    ENV["ADMIN_EMAIL"] = "team@cinquante.test"
    ENV["ADMIN_PASSWORD"] = "password1234"
    assert_raises(SystemExit) { run_task "admin:bootstrap" }
    assert_equal 0, AdminUser.count
    assert_equal 0, AdminAction.count

    ENV.delete("ADMIN_EMAIL")
    assert_raises(SystemExit) { run_task "admin:bootstrap" }
  end

  test "reset_two_factor starts the enrolment over: new secret, new link, all sessions ended" do
    admin = AdminUser.create!(email: "team@cinquante.test", password: PASSWORD)
    admin.update!(otp_secret: AdminUser.generate_otp_secret, otp_required_for_login: true)
    old_secret = admin.otp_secret
    old_salt = admin.authenticatable_salt

    ENV["ADMIN_EMAIL"] = "team@cinquante.test"
    out, = run_task("admin:reset_two_factor")
    admin.reload
    assert_not admin.two_factor_enrolled?
    assert_not_equal old_secret, admin.otp_secret
    assert_not_equal old_salt, admin.authenticatable_salt
    assert_match(%r{/admin/two_factor/link/}, out)
    assert_equal "admin.two_factor_reset", AdminAction.order(:id).last.action

    ENV["ADMIN_EMAIL"] = "nobody@cinquante.test"
    assert_raises(SystemExit) { run_task "admin:reset_two_factor" }
  end
end
