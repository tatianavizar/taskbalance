# The one door to /admin: a signed-in AdminUser whose sign-in went through
# the second factor. Used as ActiveAdmin's `authentication_method`
# (config/initializers/active_admin.rb) and included into its controllers.
#
# `session[SESSION_KEY]` is set by exactly two things: the Warden hook in
# config/initializers/two_factor.rb (a sign-in that carried a valid TOTP code)
# and BackOffice::TwoFactorsController (the first code of an enrolment). A
# password alone never sets it, so a password-only session cannot read a page.
module BackOfficeGate
  SESSION_KEY = "admin_two_factor_verified".freeze

  extend ActiveSupport::Concern

  def authenticate_admin_user_with_two_factor!
    authenticate_admin_user!
    return if two_factor_verified?

    if current_admin_user.two_factor_enrolled?
      # Enrolled, yet this session never gave a code: start over.
      sign_out(:admin_user)
      redirect_to new_admin_user_session_path, alert: t("back_office.sessions.code_required")
    else
      redirect_to back_office_two_factor_path
    end
  end

  def two_factor_verified?
    admin_signed_in = current_admin_user&.two_factor_enrolled?
    admin_signed_in && warden.session(:admin_user)[SESSION_KEY] == true
  end

  def mark_two_factor_verified!
    warden.session(:admin_user)[SESSION_KEY] = true
  end
end
