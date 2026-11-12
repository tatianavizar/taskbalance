# Signing in to /admin for tests: through the real form, so the Warden hooks that
# record the second factor run (Devise's `sign_in` helper skips the strategy).
module BackOfficeHelpers
  ADMIN_PASSWORD = "a long enough password".freeze

  # `enrolled: false` gives an admin whose enrolment link was issued (as
  # `admin:bootstrap` does); the token is in `@enrolment_tokens[admin.id]`.
  def create_admin(enrolled: true, email: "team@cinquante.test")
    admin = AdminUser.create!(email: email, password: ADMIN_PASSWORD, password_confirmation: ADMIN_PASSWORD)
    if enrolled
      admin.update!(otp_secret: AdminUser.generate_otp_secret, otp_required_for_login: true)
    else
      (@enrolment_tokens ||= {})[admin.id] = admin.issue_enrolment!
    end
    admin
  end

  def enrolment_token(admin)
    @enrolment_tokens.fetch(admin.id)
  end

  # Opens the one-time link, as the person does with the printed URL.
  def open_enrolment_link(admin, token: enrolment_token(admin))
    get back_office_two_factor_link_path(token: token)
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

  # A new admin through the whole path: link, password, first code.
  def enrol_admin!(admin = create_admin(enrolled: false))
    open_enrolment_link(admin)
    sign_in_admin(admin, otp: "")
    get "/admin/two_factor"
    post "/admin/two_factor", params: { code: otp_code(admin) }
    admin
  end
end

ActionDispatch::IntegrationTest.include BackOfficeHelpers
