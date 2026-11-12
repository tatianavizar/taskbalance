require "test_helper"
require "rake"

# `bin/rails admin:bootstrap` and `admin:reset_two_factor` (lib/tasks/admin.rake).
class AdminBootstrapTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:bootstrap")
    @env = ENV.to_h.slice("ADMIN_EMAIL", "ADMIN_PASSWORD")
  end

  teardown do
    ENV.delete("ADMIN_EMAIL")
    ENV.delete("ADMIN_PASSWORD")
    @env.each { |key, value| ENV[key] = value }
  end

  def run_task(name)
    task = Rake::Task[name]
    task.reenable
    capture_io { task.invoke }
  end

  test "creates the first admin from ENV, not yet enrolled" do
    ENV["ADMIN_EMAIL"] = " Team@Cinquante.test "
    ENV["ADMIN_PASSWORD"] = "a long enough password"

    assert_difference "AdminUser.count", 1 do
      run_task "admin:bootstrap"
    end
    admin = AdminUser.find_by!(email: "team@cinquante.test")
    assert admin.valid_password?("a long enough password")
    assert_not admin.two_factor_enrolled?
  end

  test "running it again resets the password and creates nobody" do
    ENV["ADMIN_EMAIL"] = "team@cinquante.test"
    ENV["ADMIN_PASSWORD"] = "a long enough password"
    run_task "admin:bootstrap"

    ENV["ADMIN_PASSWORD"] = "another long password"
    assert_no_difference "AdminUser.count" do
      run_task "admin:bootstrap"
    end
    assert AdminUser.find_by!(email: "team@cinquante.test").valid_password?("another long password")
  end

  test "refuses a short password and a missing ENV" do
    ENV["ADMIN_EMAIL"] = "team@cinquante.test"
    ENV["ADMIN_PASSWORD"] = "short"
    assert_raises(SystemExit) { run_task "admin:bootstrap" }
    assert_equal 0, AdminUser.count

    ENV.delete("ADMIN_EMAIL")
    assert_raises(SystemExit) { run_task "admin:bootstrap" }
  end

  test "reset_two_factor starts the enrolment over" do
    admin = AdminUser.create!(email: "team@cinquante.test", password: "a long enough password")
    admin.ensure_otp_secret!
    admin.update!(otp_required_for_login: true)

    ENV["ADMIN_EMAIL"] = "team@cinquante.test"
    run_task "admin:reset_two_factor"
    admin.reload
    assert_not admin.two_factor_enrolled?
    assert_nil admin.otp_secret
  end
end
