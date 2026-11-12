# Signing in to /admin for tests: through the real form, so the Warden hook that
# records the second factor runs (Devise's `sign_in` helper skips it).
module BackOfficeHelpers
  ADMIN_PASSWORD = "a long enough password".freeze

  def create_admin(enrolled: true, email: "team@cinquante.test")
    admin = AdminUser.create!(email: email, password: ADMIN_PASSWORD, password_confirmation: ADMIN_PASSWORD)
    if enrolled
      admin.ensure_otp_secret!
      admin.update!(otp_required_for_login: true)
    end
    admin
  end

  # The code the authenticator app shows right now.
  def otp_code(admin)
    ROTP::TOTP.new(admin.reload.otp_secret).now
  end

  def sign_in_admin(admin, otp: :valid, password: ADMIN_PASSWORD)
    code = otp == :valid ? otp_code(admin) : otp.to_s
    post admin_user_session_path, params: { admin_user: { email: admin.email, password: password, otp_attempt: code } }
  end

  # An enrolled admin, signed in with a code.
  def sign_in_team!
    admin = create_admin
    sign_in_admin(admin)
    admin
  end
end

ActionDispatch::IntegrationTest.include BackOfficeHelpers
